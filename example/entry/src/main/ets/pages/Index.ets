import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { DbService } from '../database/DbService';
import { User } from '../entity/User';
import { Post } from '../entity/Post';

@Entry
@Component
struct Index {
  @State users: User[] = [];
  @State status: string = 'Opening database…';
  @State adultsOnly: boolean = false;
  @State expandedUserId: number = -1;
  @State expandedPosts: Post[] = [];

  // "Published feed" mode
  @State showPublished: boolean = false;
  @State publishedPosts: Post[] = [];

  // Search
  @State searchTerm: string = '';
  @State searchResults: User[] = [];

  // Form fields
  @State name: string = '';
  @State email: string = '';
  @State age: string = '';
  @State bio: string = '';

  async aboutToAppear(): Promise<void> {
    try {
      await DbService.init(getContext(this) as common.Context);
      await this.refresh();
    } catch (e) {
      this.fail('init', e);
    }
  }

  /** Demonstrates ArkORM.close() — the store is reopened by init() next time. */
  async aboutToDisappear(): Promise<void> {
    await DbService.close();
  }

  // ---- data ---------------------------------------------------------------

  async refresh(): Promise<void> {
    try {
      this.users = this.adultsOnly ? await DbService.listAdults() : await DbService.listUsers();
      const total = await DbService.countUsers();
      this.status = `${this.users.length} shown · ${total} total user(s)`;
    } catch (e) {
      this.fail('refresh', e);
    }
  }

  /** Loads the published-only post feed (the v2 `published` query). */
  async loadPublished(): Promise<void> {
    try {
      this.publishedPosts = await DbService.listPublishedPosts();
      this.status = `${this.publishedPosts.length} published post(s)`;
    } catch (e) {
      this.fail('published', e);
    }
  }

  /** Reloads whichever view is currently active. */
  async reloadCurrent(): Promise<void> {
    if (this.showPublished) {
      await this.loadPublished();
    } else {
      await this.refresh();
      if (this.searchTerm.trim().length > 0) {
        await this.onSearch();
      }
    }
  }

  async onAdd(): Promise<void> {
    if (this.name.trim().length === 0 || this.email.trim().length === 0) {
      promptAction.showToast({ message: 'Name and email are required' });
      return;
    }
    try {
      const parsedAge: number | null = this.age.trim().length === 0 ? null : Number.parseInt(this.age);
      const parsedBio: string | null = this.bio.trim().length === 0 ? null : this.bio.trim();
      const id: number = await DbService.addUser(this.name.trim(), this.email.trim(), parsedAge, parsedBio);
      if (id < 0) {
        promptAction.showToast({ message: 'That email already exists' });
        return;
      }
      this.name = '';
      this.email = '';
      this.age = '';
      this.bio = '';
      await this.reloadCurrent();
      promptAction.showToast({ message: 'User added' });
    } catch (e) {
      this.fail('add', e);
    }
  }

  async onDelete(user: User): Promise<void> {
    try {
      await DbService.deleteUser(user);
      if (this.expandedUserId === user.id) {
        this.expandedUserId = -1;
        this.expandedPosts = [];
      }
      await this.reloadCurrent();
    } catch (e) {
      this.fail('delete', e);
    }
  }

  async onTogglePosts(user: User): Promise<void> {
    if (this.expandedUserId === user.id) {
      this.expandedUserId = -1;
      this.expandedPosts = [];
      return;
    }
    try {
      // Lazy relation load (.load) — see the eager variant in onTogglePostPublished.
      const full = await DbService.getUserWithPostsLazy(user.id);
      this.expandedUserId = user.id;
      this.expandedPosts = full !== null ? full.posts : [];
    } catch (e) {
      this.fail('load posts', e);
    }
  }

  async onAddPost(user: User): Promise<void> {
    try {
      await DbService.addPost(user.id, 'Draft note', 'Written from the UI.', false, ['draft', 'ui']);
      const full = await DbService.getUserWithPosts(user.id);   // eager re-read
      this.expandedUserId = user.id;
      this.expandedPosts = full !== null ? full.posts : [];
      promptAction.showToast({ message: 'Draft post added' });
    } catch (e) {
      this.fail('add post', e);
    }
  }

  async onSeedMany(): Promise<void> {
    try {
      const n: number = await DbService.seedManyUsers();
      await this.reloadCurrent();
      promptAction.showToast({ message: `Batch inserted ${n} new user(s)` });
    } catch (e) {
      this.fail('seed many', e);
    }
  }

  async onStats(): Promise<void> {
    try {
      this.status = await DbService.statsReport();
      promptAction.showToast({ message: this.status });
    } catch (e) {
      this.fail('stats', e);
    }
  }

  async onSearch(): Promise<void> {
    if (this.searchTerm.trim().length === 0) {
      this.searchResults = [];
      return;
    }
    try {
      this.searchResults = await DbService.searchUsers(this.searchTerm.trim());
    } catch (e) {
      this.fail('search', e);
    }
  }

  async onTogglePostPublished(post: Post): Promise<void> {
    try {
      await DbService.setPostPublished(post, !post.published);
      // Re-read whatever is currently on screen so the change is reflected.
      if (this.expandedUserId >= 0) {
        const full = await DbService.getUserWithPosts(this.expandedUserId);
        this.expandedPosts = full !== null ? full.posts : [];
      }
      if (this.showPublished) {
        await this.loadPublished();
      }
    } catch (e) {
      this.fail('toggle post', e);
    }
  }

  async onSeed(): Promise<void> {
    try {
      await DbService.seedDemo();
      await this.reloadCurrent();
      promptAction.showToast({ message: 'Seeded in one transaction' });
    } catch (e) {
      this.fail('seed', e);
    }
  }

  async onClear(): Promise<void> {
    try {
      await DbService.clearAll();
      this.expandedUserId = -1;
      this.expandedPosts = [];
      await this.reloadCurrent();
    } catch (e) {
      this.fail('clear', e);
    }
  }

  fail(where: string, e: Object): void {
    const err = e as BusinessError;
    const msg: string = err.message !== undefined ? err.message : JSON.stringify(e);
    this.status = `✗ ${where}: ${msg}`;
    promptAction.showToast({ message: this.status });
  }

  // ---- ui -----------------------------------------------------------------

  @Builder
  postRow(post: Post) {
    Column() {
      Row() {
        Text(post.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#333333').layoutWeight(1)
        // Tap to flip published ⇄ draft.
        Button(post.published ? '✓ published' : 'draft')
          .fontSize(11).height(26).padding({ left: 8, right: 8 })
          .fontColor(post.published ? '#2e7d32' : '#9e9e9e')
          .backgroundColor(post.published ? '#e8f5e9' : '#f0f0f0')
          .onClick(() => this.onTogglePostPublished(post))
      }
      .width('100%')
      Text(post.body).fontSize(12).fontColor('#888888').margin({ top: 2 })
      if (post.tags.length > 0) {
        Text('#' + post.tags.join('  #')).fontSize(11).fontColor('#5e35b1').margin({ top: 2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 12, top: 6, bottom: 6 })
    .borderWidth({ left: 2 })
    .borderColor(post.published ? '#4caf50' : '#cccccc')
    .margin({ top: 6 })
  }

  @Builder
  userCard(user: User) {
    Column() {
      Row() {
        Column() {
          Text(user.name).fontSize(17).fontWeight(FontWeight.Bold)
          Text(user.email).fontSize(13).fontColor('#777777').margin({ top: 2 })
          Text(user.age !== null ? `age ${user.age}` : 'age —')
            .fontSize(12).fontColor('#aaaaaa').margin({ top: 2 })
          if (user.bio !== null && user.bio.length > 0) {
            Text(user.bio).fontSize(12).fontColor('#7a8a99').margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button(this.expandedUserId === user.id ? 'Hide' : 'Posts')
          .fontSize(13).height(34).backgroundColor('#e8f5e9').fontColor('#2e7d32')
          .onClick(() => this.onTogglePosts(user))
        Button('Delete')
          .fontSize(13).height(34).margin({ left: 8 })
          .backgroundColor('#ffebee').fontColor('#c62828')
          .onClick(() => this.onDelete(user))
      }
      .width('100%')

      if (this.expandedUserId === user.id) {
        if (this.expandedPosts.length === 0) {
          Text('No posts yet').fontSize(12).fontColor('#aaaaaa').margin({ top: 8 })
        } else {
          ForEach(this.expandedPosts, (post: Post) => {
            this.postRow(post)
          }, (post: Post) => `post-${post.id}-${post.published}`)
        }
        Button('＋ Add draft post')
          .fontSize(12).height(32).margin({ top: 8 })
          .backgroundColor('#ede7f6').fontColor('#5e35b1')
          .onClick(() => this.onAddPost(user))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#ffffff')
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  publishedCard(post: Post) {
    Column() {
      Text(post.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333333')
      Text(post.body).fontSize(13).fontColor('#888888').margin({ top: 4 })
      if (post.tags.length > 0) {
        Text('#' + post.tags.join('  #')).fontSize(11).fontColor('#5e35b1').margin({ top: 4 })
      }
      Row() {
        Text(post.author !== null ? `by ${post.author.name}` : 'by unknown')
          .fontSize(12).fontColor('#2e7d32').layoutWeight(1)
        Button('Unpublish')
          .fontSize(12).height(30).backgroundColor('#fbe9e7').fontColor('#d84315')
          .onClick(() => this.onTogglePostPublished(post))
      }
      .width('100%').margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#ffffff')
    .borderRadius(12)
    .borderWidth({ left: 3 })
    .borderColor('#4caf50')
    .margin({ bottom: 10 })
  }

  /**
   * The list to display: search results while searching, otherwise all users.
   * A plain method (NOT an @Builder) — build() reads it fresh on every state
   * change, so the ForEach stays reactive to seed/clear/search/adults updates.
   */
  displayedUsers(): User[] {
    return this.searchTerm.trim().length > 0 ? this.searchResults : this.users;
  }

  build() {
    Column() {
      // Header
      Text('ArkORM Demo')
        .fontSize(24).fontWeight(FontWeight.Bold).width('100%')
      Text(this.status)
        .fontSize(13).fontColor('#666666').width('100%').margin({ top: 4, bottom: 12 })

      // Add form
      Column({ space: 8 }) {
        TextInput({ placeholder: 'Name', text: this.name })
          .height(44).backgroundColor('#ffffff').borderRadius(8)
          .borderWidth(1).borderColor('#e0e0e0')
          .onChange((v: string) => { this.name = v; })
        TextInput({ placeholder: 'Email', text: this.email })
          .type(InputType.Email)
          .height(44).backgroundColor('#ffffff').borderRadius(8)
          .borderWidth(1).borderColor('#e0e0e0')
          .onChange((v: string) => { this.email = v; })
        TextInput({ placeholder: 'Age (optional)', text: this.age })
          .type(InputType.Number)
          .height(44).backgroundColor('#ffffff').borderRadius(8)
          .borderWidth(1).borderColor('#e0e0e0')
          .onChange((v: string) => { this.age = v; })
        TextInput({ placeholder: 'Bio (optional, v2 column)', text: this.bio })
          .height(44).backgroundColor('#ffffff').borderRadius(8)
          .borderWidth(1).borderColor('#e0e0e0')
          .onChange((v: string) => { this.bio = v; })
        Button('Add User').width('100%').height(44)
          .onClick(() => this.onAdd())
      }
      .padding(14).backgroundColor('#f0f0f0').borderRadius(12).margin({ bottom: 12 })

      // Action bar
      Row({ space: 8 }) {
        Button(this.adultsOnly ? 'Show All' : 'Adults Only')
          .layoutWeight(1).fontSize(13).height(38).backgroundColor('#e3f2fd').fontColor('#1565c0')
          .onClick(() => {
            this.adultsOnly = !this.adultsOnly;
            this.refresh();
          })
        Button('Seed')
          .layoutWeight(1).fontSize(13).height(38).backgroundColor('#ede7f6').fontColor('#5e35b1')
          .onClick(() => this.onSeed())
        Button('Clear')
          .layoutWeight(1).fontSize(13).height(38).backgroundColor('#fbe9e7').fontColor('#d84315')
          .onClick(() => this.onClear())
      }
      .width('100%').margin({ bottom: 8 })

      // Second action row: batch insert + raw-SQL stats
      Row({ space: 8 }) {
        Button('Seed +5 (batch)')
          .layoutWeight(1).fontSize(13).height(38).backgroundColor('#e8f5e9').fontColor('#2e7d32')
          .onClick(() => this.onSeedMany())
        Button('Stats (raw SQL)')
          .layoutWeight(1).fontSize(13).height(38).backgroundColor('#fff3e0').fontColor('#e65100')
          .onClick(() => this.onStats())
      }
      .width('100%').margin({ bottom: 12 })

      // Search (like + or) — only meaningful in the Users view
      if (!this.showPublished) {
        TextInput({ placeholder: '🔍 Search name or email', text: this.searchTerm })
          .height(42).backgroundColor('#ffffff').borderRadius(8)
          .borderWidth(1).borderColor('#e0e0e0').margin({ bottom: 12 })
          .onChange((v: string) => {
            this.searchTerm = v;
            this.onSearch();
          })
      }

      // Mode switch: Users  ⇄  Published feed
      Button(this.showPublished ? '👥 Show Users' : '📣 Show Published Feed')
        .width('100%').height(40).fontSize(14)
        .backgroundColor('#eceff1').fontColor('#37474f')
        .margin({ bottom: 12 })
        .onClick(() => {
          this.showPublished = !this.showPublished;
          this.reloadCurrent();
        })

      // List — published feed or users, depending on mode
      if (this.showPublished) {
        if (this.publishedPosts.length === 0) {
          Column() {
            Text('No published posts').fontSize(15).fontColor('#999999')
            Text('Tap Seed for sample data').fontSize(12).fontColor('#bbbbbb').margin({ top: 4 })
          }
          .width('100%').padding({ top: 40 })
        } else {
          List() {
            ForEach(this.publishedPosts, (post: Post) => {
              ListItem() {
                this.publishedCard(post)
              }
            }, (post: Post) => `pub-${post.id}`)
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
      } else {
        // Users (or search results) — inlined so the ForEach stays reactive.
        if (this.displayedUsers().length === 0) {
          Column() {
            Text(this.searchTerm.trim().length > 0 ? 'No matches' : 'No users yet')
              .fontSize(15).fontColor('#999999')
            Text('Add one above, or tap Seed').fontSize(12).fontColor('#bbbbbb').margin({ top: 4 })
          }
          .width('100%').padding({ top: 40 })
        } else {
          List() {
            ForEach(this.displayedUsers(), (user: User) => {
              ListItem() {
                this.userCard(user)
              }
            }, (user: User) => `user-${user.id}`)
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
      }
    }
    .height('100%').width('100%')
    .padding({ left: 16, right: 16, top: 16 })
    .backgroundColor('#fafafa')
  }
}
